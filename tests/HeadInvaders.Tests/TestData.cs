using System;
using System.IO;

using HeadInvaders.Tracking;
using StbImageSharp;
using Xunit;

namespace HeadInvaders.Tests
{
    /// <summary>Load the models and the test photos.</summary>
    /// <remarks>
    /// <para>All test photos are public-domain NASA photos, fitted into black
    /// 640x480 frames like webcam frames:</para>
    /// <list type="bullet">
    /// <item>astronaut_640x480.png: Eileen Collins (scikit-image "astronaut")</item>
    /// <item>mission_control_from_behind_640x480.png: "Flight Controllers in Mission
    /// Control Center during splashdown of Apollo 14 (S71-18400)"</item>
    /// <item>crew_of_six_640x480.png: "Expedition 38 crew members pose for an
    /// in-flight crew portrait (ISS038-E-054970)"</item>
    /// </list>
    /// </remarks>
    public static class TestData
    {
        public const int Width = 640;
        public const int Height = 480;

        public const string UltraFace = "version-RFB-320.onnx";
        public const string Yolox = "yolox_n_body_head_hand_face_post_1x3x256x320.onnx";
        public const string OsNet = "osnet_x0_25_msmt17.onnx";

        public static string Path(string fileName)
        {
            return System.IO.Path.Combine(AppContext.BaseDirectory, "data", fileName);
        }

        public static byte[] LoadModel(string fileName)
        {
            string path = Path(fileName);
            byte[] model = File.ReadAllBytes(path);

            // NOTE (mristin):
            // If git-lfs has not been pulled, we get a tiny pointer file instead of
            // the model. We fail early with a helpful message in that case.
            Assert.True(
                model.Length > 100_000,
                $"The model at {path} looks like a git-lfs pointer; run `git lfs pull`."
            );

            return model;
        }

        public static Frame LoadFrame(string fileName)
        {
            using var stream = File.OpenRead(Path(fileName));
            var image = ImageResult.FromStream(stream, ColorComponents.RedGreenBlue);

            Assert.Equal(Width, image.Width);
            Assert.Equal(Height, image.Height);

            return new Frame(image.Data, image.Width, image.Height, 0.0);
        }
    }
}
