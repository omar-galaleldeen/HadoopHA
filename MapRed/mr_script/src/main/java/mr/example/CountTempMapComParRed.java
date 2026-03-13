package mr.example;

import java.io.IOException;

import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.DoubleWritable;
import org.apache.hadoop.io.LongWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.Mapper;
import org.apache.hadoop.mapreduce.Partitioner;
import org.apache.hadoop.mapreduce.Reducer;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;

public class CountTempMapComParRed {
	public static void main(String[] args) throws Exception {
		if (args.length != 2) {
			System.err.println("Usage: CountTemperatureMapperCombinerPartitionerReducer <input path> <output path>");
			System.exit(-1);
		}

		// Job configuration
		//Configuration conf = new Configuration();
		//conf.set("mapreduce.job.queuename", "root.batch_jobs");
		//Job job = new Job(conf);
		Job job = new Job();
		job.setJarByClass(CountTempMapComParRed.class);
		job.setJobName("Count temperature");
		job.setNumReduceTasks(12);
		// edit the previous line for number of reducers
		job.setMapperClass(TemperatureMapper2.class);
		job.setCombinerClass(TemperatureReducer2.class);
		job.setPartitionerClass(TemperaturePartitioner2.class);
		job.setReducerClass(TemperatureReducer2.class);
		job.setOutputKeyClass(Text.class);
		job.setOutputValueClass(DoubleWritable.class);

		// Input & Output
		FileInputFormat.addInputPath(job, new Path(args[0]));
		FileOutputFormat.setOutputPath(job, new Path(args[1]));

		// Run Job
		System.exit(job.waitForCompletion(true) ? 0 : 1);
	}
}

class TemperatureMapper2 extends Mapper<LongWritable, Text, Text, DoubleWritable> {
	@Override
	public void map(LongWritable key, Text value, Context context) throws IOException, InterruptedException {
		// get value
		String line = value.toString();

		// Ignore headers
		if (line.startsWith("STATION")) { return; }
		
		// Parse fields
		String[] fields = line.split("\\|");
		//String year = fields[2].substring(0, 4);
		String yearMonth = fields[2].substring(0, 7);
		double temperature = Double.parseDouble(fields[6]);
		int qualityCode = Integer.parseInt(fields[8]);

		// output record if valid quality code
		//if (qualityCode == 0 || qualityCode == 1) {
		//	context.write(new Text(yearMonth), new DoubleWritable(temperature));
			context.write(new Text(yearMonth), new DoubleWritable(1));
		//}

	}
}

class TemperaturePartitioner2<K2, V2> extends Partitioner<Text, DoubleWritable> {

	//public int getPartition(Text key, DoubleWritable value, int numReduceTasks) {
    //    return (int) (Integer.parseInt(key.toString()) - 1901);
    //}
	public int getPartition(Text key, DoubleWritable value, int numReduceTasks) {
        //return (int) (Integer.parseInt(key.toString()) - 1901);
		String[] parts = key.toString().split("-"); // hn5od el key ele hwa 1901-01 n2smo
        int month = Integer.parseInt(parts[1]); // 5od tani goz2 mn el splitter
        return (month - 1) % numReduceTasks; // kda enta wadet month 1 3la reducer 0 
    }
}

class TemperatureReducer2 extends Reducer<Text, DoubleWritable, Text, DoubleWritable> {
	@Override
	public void reduce(Text key, Iterable<DoubleWritable> values, Context context) throws IOException, InterruptedException {
		//double maxValue = Double.MIN_VALUE;
		int sum =0;
		for (DoubleWritable value : values) {
			//maxValue = Math.max(maxValue, value.get());
			//  5ali el logic hena ysum l2nk abl kda 3mlt count fa lw 3mlt count tani hytl3lk count el partitions asln
			sum += value.get();
		}
		//context.write(key, new DoubleWritable(maxValue));
		context.write(key, new DoubleWritable(sum));
	}
}